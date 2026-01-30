/****************************************************************************
**
** Copyright (C) 2016 The Qt Company Ltd.
** Contact: https://www.qt.io/licensing/
**
** This file is part of the examples of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:BSD$
** Commercial License Usage
** Licensees holding valid commercial Qt licenses may use this file in
** accordance with the commercial license agreement provided with the
** Software or, alternatively, in accordance with the terms contained in
** a written agreement between you and The Qt Company. For licensing terms
** and conditions see https://www.qt.io/terms-conditions. For further
** information use the contact form at https://www.qt.io/contact-us.
**
** BSD License Usage
** Alternatively, you may use this file under the terms of the BSD license
** as follows:
**
** "Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are
** met:
**   * Redistributions of source code must retain the above copyright
**     notice, this list of conditions and the following disclaimer.
**   * Redistributions in binary form must reproduce the above copyright
**     notice, this list of conditions and the following disclaimer in
**     the documentation and/or other materials provided with the
**     distribution.
**   * Neither the name of The Qt Company Ltd nor the names of its
**     contributors may be used to endorse or promote products derived
**     from this software without specific prior written permission.
**
**
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
** "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
** LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
** A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
** OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
** SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
** LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
** DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
** THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
** OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
**
** $QT_END_LICENSE$
**
****************************************************************************/

#ifndef SORTFILTERPROXYMODEL_H
#define SORTFILTERPROXYMODEL_H

#include <QtCore/qsortfilterproxymodel.h>
#include <QtQml/qqmlparserstatus.h>
#include <QtQml/qjsvalue.h>

/**
 * @brief QML-compatible proxy model for sorting and filtering
 * 
 * Extends QSortFilterProxyModel to provide QML-friendly properties.
 * Wraps a source model and adds sorting/filtering capabilities.
 */
class SortFilterProxyModel : public QSortFilterProxyModel, public QQmlParserStatus
{
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)

    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(QObject *source READ source WRITE setSource)

    Q_PROPERTY(QByteArray sortRole READ sortRole WRITE setSortRole)
    Q_PROPERTY(Qt::SortOrder sortOrder READ sortOrder WRITE setSortOrder)
    Q_PROPERTY(Qt::CaseSensitivity sortCaseSensitivity READ sortCaseSensitivity WRITE setSortCaseSensitivity)

    Q_PROPERTY(QByteArray filterRole READ filterRole WRITE setFilterRole)
    Q_PROPERTY(QString filterString READ filterString WRITE setFilterString)
    Q_PROPERTY(FilterSyntax filterSyntax READ filterSyntax WRITE setFilterSyntax)
    Q_PROPERTY(Qt::CaseSensitivity filterCaseSensitivity READ filterCaseSensitivity WRITE setFilterCaseSensitivity)
    
    Q_PROPERTY(QString renderVersionFilter READ renderVersionFilter WRITE setRenderVersionFilter NOTIFY renderVersionFilterChanged)

    Q_ENUMS(FilterSyntax)

public:
    explicit SortFilterProxyModel(QObject *parent = 0);

    QObject *source() const;
    void setSource(QObject *source);

    QByteArray sortRole() const;
    void setSortRole(const QByteArray &role);
    Qt::SortOrder sortOrder() const;
    void setSortOrder(Qt::SortOrder order);
    Qt::CaseSensitivity sortCaseSensitivity() const;
    void setSortCaseSensitivity(Qt::CaseSensitivity caseSensitivity);

    QByteArray filterRole() const;
    void setFilterRole(const QByteArray &role);
    QString filterString() const;
    void setFilterString(const QString &filter);

    enum FilterSyntax {
        RegExp,
        Wildcard,
        FixedString
    };

    FilterSyntax filterSyntax() const;
    void setFilterSyntax(FilterSyntax syntax);
    Qt::CaseSensitivity filterCaseSensitivity() const;
    void setFilterCaseSensitivity(Qt::CaseSensitivity caseSensitivity);
    
    QString renderVersionFilter() const;
    void setRenderVersionFilter(const QString &version);

    int count() const;
    
    /**
     * @brief Get row data as JavaScript object (used by QML)
     * @param index - Row index in proxy model (after sorting/filtering)
     */
    Q_INVOKABLE QJSValue get(int index) const;
    
    /**
     * @brief Map a proxy model row index to source model row index
     * @param proxyRow - Row index in the proxy model
     * @return Row index in the source model, or -1 if invalid
     */
    Q_INVOKABLE int mapProxyRowToSource(int proxyRow) const;

    Q_INVOKABLE void sort(int column, Qt::SortOrder order);

    void classBegin();
    void componentComplete();

signals:
    void countChanged();
    void renderVersionFilterChanged();

protected:
    int roleKey(const QByteArray &role) const;
    QHash<int, QByteArray> roleNames() const;
    
    /**
     * @brief Determine if row should be included after filtering
     * If filterRole is empty, searches all roles (global search).
     */
    bool filterAcceptsRow(int sourceRow, const QModelIndex &sourceParent) const;

private:
    bool m_complete;
    QByteArray m_sortRole;
    QByteArray m_filterRole;  // Empty = search all roles
    QString m_renderVersionFilter;  // Selected render version for filtering (e.g., "freedview_1.2.1.3_1.0.0.7_VS_freedView_1.3.0.0_1.0.0.1")
};

#endif // SORTFILTERPROXYMODEL_H
